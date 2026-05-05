import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:open_file/open_file.dart';
import 'package:pdf/pdf.dart';
import 'package:ghanaclass_school_management/core/constants/theme.dart';
import 'package:ghanaclass_school_management/features/staff/staff_providers.dart';
import 'package:ghanaclass_school_management/features/finance/finance_providers.dart';
import 'package:ghanaclass_school_management/features/finance/finance_service.dart';
import 'package:ghanaclass_school_management/features/finance/payroll_pdf_service.dart';
import 'package:ghanaclass_school_management/core/database/app_database.dart';
import 'package:ghanaclass_school_management/core/providers/auth_providers.dart';
import 'package:ghanaclass_school_management/shared/printing/pdf_preview_screen.dart';
import 'package:drift/drift.dart' as drift;

class PayrollScreen extends ConsumerStatefulWidget {
  const PayrollScreen({super.key});

  @override
  ConsumerState<PayrollScreen> createState() => _PayrollScreenState();
}

class _PayrollScreenState extends ConsumerState<PayrollScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;
  String _historySearch = '';
  bool _historyGroupByStaff = false;
  bool _historyExporting = false;
  bool _payslipWorking = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Staff Payroll'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Current Month / Config'),
            Tab(text: 'Payroll History'),
          ],
        ),
        actions: [
          _buildMonthPicker(),
          const SizedBox(width: 16),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCurrentMonthTab(),
          _buildHistoryTab(),
        ],
      ),
    );
  }

  Widget _buildMonthPicker() {
    return Row(
      children: [
        DropdownButton<int>(
          value: _selectedMonth,
          items: List.generate(12, (i) => DropdownMenuItem(value: i + 1, child: Text(DateFormat('MMMM').format(DateTime(2024, i + 1))))),
          onChanged: (v) => setState(() => _selectedMonth = v!),
        ),
        const SizedBox(width: 8),
        DropdownButton<int>(
          value: _selectedYear,
          items: List.generate(5, (i) => DropdownMenuItem(value: 2024 + i, child: Text((2024 + i).toString()))),
          onChanged: (v) => setState(() => _selectedYear = v!),
        ),
      ],
    );
  }

  Widget _buildCurrentMonthTab() {
    final staffAsync = ref.watch(teachersProvider); // Using teachers for now as staff

    return staffAsync.when(
      data: (staffList) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Manage staff salaries and process payroll for this month.', style: TextStyle(color: AppTheme.textMuted)),
                  ElevatedButton.icon(
                    onPressed: () => _processPayrollConfirm(context),
                    icon: const Icon(LucideIcons.play, size: 18),
                    label: const Text('Process Monthly Payroll'),
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.success, foregroundColor: Colors.white),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: staffList.length,
                itemBuilder: (context, index) {
                  final staff = staffList[index];
                  return _StaffSalaryCard(staff: staff);
                },
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  Widget _buildHistoryTab() {
    final historyAsync = ref.watch(payrollHistoryProvider((month: _selectedMonth, year: _selectedYear)));

    return historyAsync.when(
      data: (entries) {
        final query = _historySearch.trim().toLowerCase();

        final filtered = query.isEmpty
            ? entries
            : entries
                .where(
                  (e) => e.staff.fullName.toLowerCase().contains(query) || e.paidBy.fullName.toLowerCase().contains(query),
                )
                .toList(growable: false);

        final totalGross = filtered.fold<double>(0, (sum, e) => sum + e.record.grossSalary);
        final totalNet = filtered.fold<double>(0, (sum, e) => sum + e.record.netSalary);
        final totalAllowances = filtered.fold<double>(0, (sum, e) => sum + e.record.totalAllowances);
        final totalDeductions = filtered.fold<double>(0, (sum, e) => sum + e.record.totalDeductions);

        final grouped = _groupByStaff(filtered);

        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _historyExporting
                              ? null
                              : () => _exportPayrollHistoryCsv(context, filtered, groupByStaff: _historyGroupByStaff),
                          icon: const Icon(LucideIcons.fileSpreadsheet, size: 18),
                          label: Text(_historyGroupByStaff ? 'Export CSV (Grouped)' : 'Export CSV'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _historyExporting
                              ? null
                              : () => _previewPayrollHistoryPdf(context, filtered, groupByStaff: _historyGroupByStaff),
                          icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                          label: Text(_historyGroupByStaff ? 'PDF (Grouped)' : 'PDF'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _historyExporting
                              ? null
                              : () => _savePayrollHistoryPdf(context, filtered, groupByStaff: _historyGroupByStaff),
                          icon: const Icon(Icons.download_outlined, size: 18),
                          label: const Text('Save PDF'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Row(
                    children: [
                      const Text('Group by staff', style: TextStyle(color: AppTheme.textMuted)),
                      const SizedBox(width: 8),
                      Switch(
                        value: _historyGroupByStaff,
                        onChanged: (v) => setState(() => _historyGroupByStaff = v),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: _MetricTile(
                          label: 'Records',
                          value: filtered.length.toString(),
                          icon: LucideIcons.list,
                        ),
                      ),
                      Expanded(
                        child: _MetricTile(
                          label: 'Total Gross',
                          value: 'GH₵ ${totalGross.toStringAsFixed(2)}',
                          icon: LucideIcons.wallet,
                        ),
                      ),
                      Expanded(
                        child: _MetricTile(
                          label: 'Total Net',
                          value: 'GH₵ ${totalNet.toStringAsFixed(2)}',
                          icon: LucideIcons.badgeDollarSign,
                        ),
                      ),
                      Expanded(
                        child: _MetricTile(
                          label: 'Allow/Deduct',
                          value: 'GH₵ ${totalAllowances.toStringAsFixed(2)} / ${totalDeductions.toStringAsFixed(2)}',
                          icon: LucideIcons.slidersHorizontal,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  labelText: 'Search staff / processed by',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (v) => setState(() => _historySearch = v),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: filtered.isEmpty
                    ? const Center(child: Text('No payroll records found for the selected period.'))
                    : _historyGroupByStaff
                        ? ListView.separated(
                            itemCount: grouped.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final s = grouped[index];
                              return Card(
                                child: ListTile(
                                  leading: const Icon(LucideIcons.users),
                                  title: Text(s.staff.fullName),
                                  subtitle: Text(
                                    [
                                      'Records: ${s.entries.length}',
                                      'Total Net: GH₵ ${s.totalNet.toStringAsFixed(2)}',
                                      'Total Gross: GH₵ ${s.totalGross.toStringAsFixed(2)}',
                                    ].join(' • '),
                                  ),
                                  trailing: PopupMenuButton<String>(
                                    tooltip: 'Actions',
                                    onSelected: (v) async {
                                      if (v == 'payslip_latest') {
                                        await _previewPayslip(context, s.latest);
                                      } else if (v == 'save_latest') {
                                        await _savePayslipPdf(context, s.latest);
                                      } else if (v == 'print_latest') {
                                        await _printPayslip(context, s.latest);
                                      }
                                    },
                                    itemBuilder: (context) => const [
                                      PopupMenuItem(value: 'payslip_latest', child: Text('Preview latest payslip')),
                                      PopupMenuItem(value: 'save_latest', child: Text('Save latest payslip PDF')),
                                      PopupMenuItem(value: 'print_latest', child: Text('Print latest payslip')),
                                    ],
                                  ),
                                  onTap: () => _showStaffGroupDetails(context, s),
                                ),
                              );
                            },
                          )
                        : ListView.separated(
                            itemCount: filtered.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final e = filtered[index];
                              final r = e.record;
                              return Card(
                                child: ListTile(
                                  leading: const Icon(LucideIcons.receipt),
                                  title: Text(e.staff.fullName),
                                  subtitle: Text(
                                    [
                                      'Net: GH₵ ${r.netSalary.toStringAsFixed(2)}',
                                      'Gross: GH₵ ${r.grossSalary.toStringAsFixed(2)}',
                                      'Processed by: ${e.paidBy.fullName}',
                                    ].join(' • '),
                                  ),
                                  trailing: PopupMenuButton<String>(
                                    tooltip: 'Actions',
                                    onSelected: (v) async {
                                      if (v == 'details') {
                                        _showPayrollEntryDetails(context, e);
                                      } else if (v == 'payslip_preview') {
                                        await _previewPayslip(context, e);
                                      } else if (v == 'payslip_save') {
                                        await _savePayslipPdf(context, e);
                                      } else if (v == 'payslip_print') {
                                        await _printPayslip(context, e);
                                      }
                                    },
                                    itemBuilder: (context) => const [
                                      PopupMenuItem(value: 'details', child: Text('View details')),
                                      PopupMenuDivider(),
                                      PopupMenuItem(value: 'payslip_preview', child: Text('Preview payslip')),
                                      PopupMenuItem(value: 'payslip_save', child: Text('Save payslip PDF')),
                                      PopupMenuItem(value: 'payslip_print', child: Text('Print payslip')),
                                    ],
                                    child: Text(DateFormat('MMM dd, yyyy').format(r.paidAt)),
                                  ),
                                  onTap: () => _showPayrollEntryDetails(context, e),
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  void _processPayrollConfirm(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Process Payroll'),
        content: Text('Are you sure you want to generate payroll records for ${DateFormat('MMMM').format(DateTime(2024, _selectedMonth))} $_selectedYear? This will create payment logs for all eligible staff.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final admin = ref.read(currentUserProvider)!;
              await ref.read(financeServiceProvider).processPayroll(
                month: _selectedMonth,
                year: _selectedYear,
                adminId: admin.id,
              );
              if (context.mounted) {
                Navigator.pop(context);
                ref.invalidate(payrollHistoryProvider);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payroll processed successfully!')));
              }
            },
            child: const Text('Process Now'),
          ),
        ],
      ),
    );
  }

  void _showPayrollEntryDetails(BuildContext context, PayrollHistoryEntry entry) {
    final r = entry.record;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Payroll: ${entry.staff.fullName}'),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Period: ${DateFormat('MMMM').format(DateTime(r.year, r.month))} ${r.year}'),
              const SizedBox(height: 8),
              Text('Paid at: ${DateFormat('MMM dd, yyyy • HH:mm').format(r.paidAt)}'),
              const SizedBox(height: 8),
              Text('Processed by: ${entry.paidBy.fullName}'),
              const Divider(height: 24),
              Text('Gross salary: GH₵ ${r.grossSalary.toStringAsFixed(2)}'),
              Text('Allowances: GH₵ ${r.totalAllowances.toStringAsFixed(2)}'),
              Text('Deductions: GH₵ ${r.totalDeductions.toStringAsFixed(2)}'),
              const SizedBox(height: 8),
              Text('Net salary: GH₵ ${r.netSalary.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('CLOSE')),
          OutlinedButton.icon(
            onPressed: _payslipWorking ? null : () => _previewPayslip(context, entry),
            icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
            label: const Text('PREVIEW PAYSLIP'),
          ),
          OutlinedButton.icon(
            onPressed: _payslipWorking ? null : () => _savePayslipPdf(context, entry),
            icon: const Icon(Icons.download_outlined, size: 18),
            label: const Text('SAVE PDF'),
          ),
          ElevatedButton.icon(
            onPressed: _payslipWorking ? null : () => _printPayslip(context, entry),
            icon: const Icon(LucideIcons.printer, size: 18),
            label: const Text('PRINT'),
          ),
        ],
      ),
    );
  }

  List<_StaffPayrollSummary> _groupByStaff(List<PayrollHistoryEntry> entries) {
    final byId = <int, List<PayrollHistoryEntry>>{};
    for (final e in entries) {
      (byId[e.staff.id] ??= <PayrollHistoryEntry>[]).add(e);
    }

    final out = <_StaffPayrollSummary>[];
    for (final id in byId.keys) {
      final list = byId[id]!;
      list.sort((a, b) => b.record.paidAt.compareTo(a.record.paidAt));
      out.add(_StaffPayrollSummary(staff: list.first.staff, entries: list));
    }

    out.sort((a, b) => a.staff.fullName.toLowerCase().compareTo(b.staff.fullName.toLowerCase()));
    return out;
  }

  Future<InstitutionalIdentityData?> _getSchoolInfoSafe() async {
    try {
      return await ref.read(institutionalIdentityProvider.future);
    } catch (_) {
      return null;
    }
  }

  Future<void> _exportPayrollHistoryCsv(
    BuildContext context,
    List<PayrollHistoryEntry> entries, {
    required bool groupByStaff,
  }) async {
    if (_historyExporting) return;
    setState(() => _historyExporting = true);
    try {
      final defaultName = groupByStaff
          ? 'payroll_history_grouped_${_selectedYear}_${_selectedMonth.toString().padLeft(2, '0')}.csv'
          : 'payroll_history_${_selectedYear}_${_selectedMonth.toString().padLeft(2, '0')}.csv';

      final targetPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Export payroll history CSV',
        fileName: defaultName,
        type: FileType.custom,
        allowedExtensions: const ['csv'],
      );
      if (targetPath == null) return;

      final normalized = targetPath.endsWith('.csv') ? targetPath : '$targetPath.csv';

      late final String csv;
      if (groupByStaff) {
        final grouped = _groupByStaff(entries);
        final rows = <List<dynamic>>[
          const ['Staff', 'Records', 'Total Gross', 'Total Allowances', 'Total Deductions', 'Total Net'],
          for (final s in grouped)
            [
              s.staff.fullName,
              s.entries.length,
              s.totalGross.toStringAsFixed(2),
              s.totalAllowances.toStringAsFixed(2),
              s.totalDeductions.toStringAsFixed(2),
              s.totalNet.toStringAsFixed(2),
            ],
        ];
        csv = const ListToCsvConverter().convert(rows);
      } else {
        final rows = <List<dynamic>>[
          const ['Staff', 'Staff Email', 'Role', 'Gross', 'Allowances', 'Deductions', 'Net', 'Paid At', 'Processed By'],
          for (final e in entries)
            [
              e.staff.fullName,
              e.staff.email,
              e.staff.role,
              e.record.grossSalary.toStringAsFixed(2),
              e.record.totalAllowances.toStringAsFixed(2),
              e.record.totalDeductions.toStringAsFixed(2),
              e.record.netSalary.toStringAsFixed(2),
              e.record.paidAt.toIso8601String(),
              e.paidBy.fullName,
            ],
        ];
        csv = const ListToCsvConverter().convert(rows);
      }

      await File(normalized).writeAsString(csv);
      await OpenFile.open(normalized);

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('CSV exported.')));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to export CSV: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _historyExporting = false);
    }
  }

  Future<void> _previewPayrollHistoryPdf(
    BuildContext context,
    List<PayrollHistoryEntry> entries, {
    required bool groupByStaff,
  }) async {
    final schoolInfo = await _getSchoolInfoSafe();
    final fileName = (groupByStaff
            ? 'payroll_history_grouped_${_selectedYear}_${_selectedMonth.toString().padLeft(2, '0')}.pdf'
            : 'payroll_history_${_selectedYear}_${_selectedMonth.toString().padLeft(2, '0')}.pdf')
        .replaceAll(' ', '_');

    final service = PayrollHistoryReportPdfService();
    if (!context.mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PdfPreviewScreen(
          title: 'Payroll History PDF',
          subtitle: '${DateFormat('MMMM').format(DateTime(_selectedYear, _selectedMonth))} $_selectedYear',
          pdfFileName: fileName,
          canChangeOrientation: true,
          canChangePageFormat: true,
          buildPdf: (format) => service.buildPayrollHistoryReportPdf(
            entries: entries,
            month: _selectedMonth,
            year: _selectedYear,
            schoolInfo: schoolInfo,
            pageFormat: format,
            groupByStaff: groupByStaff,
          ),
        ),
      ),
    );
  }

  Future<void> _savePayrollHistoryPdf(
    BuildContext context,
    List<PayrollHistoryEntry> entries, {
    required bool groupByStaff,
  }) async {
    if (_historyExporting) return;
    setState(() => _historyExporting = true);
    try {
      final schoolInfo = await _getSchoolInfoSafe();

      final defaultName = (groupByStaff
              ? 'payroll_history_grouped_${_selectedYear}_${_selectedMonth.toString().padLeft(2, '0')}.pdf'
              : 'payroll_history_${_selectedYear}_${_selectedMonth.toString().padLeft(2, '0')}.pdf')
          .replaceAll(' ', '_');

      final targetPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save payroll history PDF',
        fileName: defaultName,
        type: FileType.custom,
        allowedExtensions: const ['pdf'],
      );
      if (targetPath == null) return;

      final normalized = targetPath.endsWith('.pdf') ? targetPath : '$targetPath.pdf';
      final bytes = await PayrollHistoryReportPdfService().buildPayrollHistoryReportPdf(
        entries: entries,
        month: _selectedMonth,
        year: _selectedYear,
        schoolInfo: schoolInfo,
        pageFormat: PdfPageFormat.a4,
        groupByStaff: groupByStaff,
      );
      await File(normalized).writeAsBytes(bytes);
      await OpenFile.open(normalized);

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PDF saved.')));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save PDF: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _historyExporting = false);
    }
  }

  Future<void> _previewPayslip(BuildContext context, PayrollHistoryEntry entry) async {
    if (_payslipWorking) return;
    setState(() => _payslipWorking = true);
    try {
      final schoolInfo = await _getSchoolInfoSafe();
      final fileName = 'payslip_${entry.staff.fullName}_${entry.record.year}_${entry.record.month.toString().padLeft(2, '0')}.pdf'
          .replaceAll(' ', '_');
      final service = PayrollPayslipPdfService();

      if (!context.mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PdfPreviewScreen(
            title: 'Payslip',
            subtitle: '${entry.staff.fullName} • ${DateFormat('MMMM').format(DateTime(entry.record.year, entry.record.month))} ${entry.record.year}',
            pdfFileName: fileName,
            canChangeOrientation: false,
            canChangePageFormat: true,
            buildPdf: (format) => service.buildPayslipPdf(
              entry: entry,
              schoolInfo: schoolInfo,
              pageFormat: format,
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _payslipWorking = false);
    }
  }

  Future<void> _savePayslipPdf(BuildContext context, PayrollHistoryEntry entry) async {
    if (_payslipWorking) return;
    setState(() => _payslipWorking = true);
    try {
      final schoolInfo = await _getSchoolInfoSafe();

      final defaultName = 'payslip_${entry.staff.fullName}_${entry.record.year}_${entry.record.month.toString().padLeft(2, '0')}.pdf'
          .replaceAll(' ', '_');

      final targetPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save payslip PDF',
        fileName: defaultName,
        type: FileType.custom,
        allowedExtensions: const ['pdf'],
      );
      if (targetPath == null) return;

      final normalized = targetPath.endsWith('.pdf') ? targetPath : '$targetPath.pdf';
      final bytes = await PayrollPayslipPdfService().buildPayslipPdf(
        entry: entry,
        schoolInfo: schoolInfo,
        pageFormat: PdfPageFormat.a4,
      );
      await File(normalized).writeAsBytes(bytes);
      await OpenFile.open(normalized);

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payslip saved.')));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save payslip: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _payslipWorking = false);
    }
  }

  Future<void> _printPayslip(BuildContext context, PayrollHistoryEntry entry) async {
    if (_payslipWorking) return;
    setState(() => _payslipWorking = true);
    try {
      final schoolInfo = await _getSchoolInfoSafe();
      await PayrollPayslipPdfService().printPayslip(entry: entry, schoolInfo: schoolInfo);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payslip sent to printer.')));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to print payslip: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _payslipWorking = false);
    }
  }

  void _showStaffGroupDetails(BuildContext context, _StaffPayrollSummary summary) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Payroll: ${summary.staff.fullName}'),
          content: SizedBox(
            width: 720,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Records: ${summary.entries.length}'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    Chip(label: Text('Gross: GH₵ ${summary.totalGross.toStringAsFixed(2)}')),
                    Chip(label: Text('Allow: GH₵ ${summary.totalAllowances.toStringAsFixed(2)}')),
                    Chip(label: Text('Deduct: GH₵ ${summary.totalDeductions.toStringAsFixed(2)}')),
                    Chip(label: Text('Net: GH₵ ${summary.totalNet.toStringAsFixed(2)}')),
                  ],
                ),
                const Divider(height: 24),
                SizedBox(
                  height: 360,
                  child: ListView.separated(
                    itemCount: summary.entries.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final e = summary.entries[index];
                      final r = e.record;
                      return Card(
                        child: ListTile(
                          leading: const Icon(LucideIcons.receipt),
                          title: Text('Net: GH₵ ${r.netSalary.toStringAsFixed(2)} • Gross: GH₵ ${r.grossSalary.toStringAsFixed(2)}'),
                          subtitle: Text('Paid: ${DateFormat('MMM dd, yyyy • HH:mm').format(r.paidAt)} • Processed by: ${e.paidBy.fullName}'),
                          trailing: PopupMenuButton<String>(
                            onSelected: (v) async {
                              if (v == 'preview') {
                                await _previewPayslip(context, e);
                              } else if (v == 'save') {
                                await _savePayslipPdf(context, e);
                              } else if (v == 'print') {
                                await _printPayslip(context, e);
                              }
                            },
                            itemBuilder: (context) => const [
                              PopupMenuItem(value: 'preview', child: Text('Preview payslip')),
                              PopupMenuItem(value: 'save', child: Text('Save payslip PDF')),
                              PopupMenuItem(value: 'print', child: Text('Print payslip')),
                            ],
                          ),
                          onTap: () => _showPayrollEntryDetails(context, e),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('CLOSE')),
          ],
        );
      },
    );
  }
}

class _StaffPayrollSummary {
  final User staff;
  final List<PayrollHistoryEntry> entries;

  const _StaffPayrollSummary({
    required this.staff,
    required this.entries,
  });

  PayrollHistoryEntry get latest => entries.first;

  double get totalGross => entries.fold<double>(0, (s, e) => s + e.record.grossSalary);
  double get totalNet => entries.fold<double>(0, (s, e) => s + e.record.netSalary);
  double get totalAllowances => entries.fold<double>(0, (s, e) => s + e.record.totalAllowances);
  double get totalDeductions => entries.fold<double>(0, (s, e) => s + e.record.totalDeductions);
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _MetricTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.textMuted),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }
}

class _StaffSalaryCard extends ConsumerWidget {
  final User staff;
  const _StaffSalaryCard({required this.staff});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final salaryAsync = ref.watch(staffSalaryProvider(staff.id));

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(child: Text(staff.fullName[0].toUpperCase())),
        title: Text(staff.fullName),
        subtitle: salaryAsync.when(
          data: (s) => Text(s == null || s.baseSalary == 0 
            ? 'Salary not configured' 
            : 'Base: GH₵ ${s.baseSalary.toStringAsFixed(2)}'),
          loading: () => const Text('Loading...'),
          error: (error, stackTrace) => const Text('Error loading salary'),
        ),
        trailing: ElevatedButton(
          onPressed: () => _showSalaryEditor(context, ref, salaryAsync.value),
          child: const Text('Edit Salary'),
        ),
      ),
    );
  }

  void _showSalaryEditor(BuildContext context, WidgetRef ref, StaffSalary? current) {
    showDialog(
      context: context,
      builder: (context) => _SalaryEditorDialog(staff: staff, current: current),
    ).then((_) => ref.invalidate(staffSalaryProvider(staff.id)));
  }
}

class _SalaryEditorDialog extends StatefulWidget {
  final User staff;
  final StaffSalary? current;
  const _SalaryEditorDialog({required this.staff, this.current});

  @override
  State<_SalaryEditorDialog> createState() => _SalaryEditorDialogState();
}

class _SalaryEditorDialogState extends State<_SalaryEditorDialog> {
  late TextEditingController _baseController;
  final List<Map<String, dynamic>> _allowances = [];
  final List<Map<String, dynamic>> _deductions = [];

  @override
  void initState() {
    super.initState();
    _baseController = TextEditingController(text: widget.current?.baseSalary.toString() ?? '0');
    if (widget.current?.allowances != null) {
      _allowances.addAll(List<Map<String, dynamic>>.from(jsonDecode(widget.current!.allowances!)));
    }
    if (widget.current?.deductions != null) {
      _deductions.addAll(List<Map<String, dynamic>>.from(jsonDecode(widget.current!.deductions!)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Configure Salary: ${widget.staff.fullName}'),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _baseController,
                decoration: const InputDecoration(labelText: 'Base Salary (GH₵)', border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 24),
              _buildSection('Allowances', _allowances),
              const SizedBox(height: 24),
              _buildSection('Deductions', _deductions),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        Consumer(builder: (context, ref, _) {
          return ElevatedButton(
            onPressed: () async {
              final base = double.tryParse(_baseController.text) ?? 0.0;
              await ref.read(financeServiceProvider).upsertStaffSalary(StaffSalariesCompanion(
                staffId: drift.Value(widget.staff.id),
                baseSalary: drift.Value(base),
                allowances: drift.Value(jsonEncode(_allowances)),
                deductions: drift.Value(jsonEncode(_deductions)),
              ));
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Save Configuration'),
          );
        }),
      ],
    );
  }

  Widget _buildSection(String title, List<Map<String, dynamic>> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            IconButton(
              icon: const Icon(Icons.add, size: 18),
              onPressed: () => _addItem(items),
            ),
          ],
        ),
        ...items.asMap().entries.map((entry) {
          final i = entry.key;
          final item = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Row(
              children: [
                Expanded(child: TextFormField(
                  initialValue: item['name'],
                  onChanged: (v) => item['name'] = v,
                  decoration: const InputDecoration(hintText: 'Name', isDense: true),
                )),
                const SizedBox(width: 8),
                Expanded(child: TextFormField(
                  initialValue: item['amount'].toString(),
                  onChanged: (v) => item['amount'] = double.tryParse(v) ?? 0.0,
                  decoration: const InputDecoration(hintText: 'Amount', isDense: true),
                  keyboardType: TextInputType.number,
                )),
                IconButton(icon: const Icon(Icons.remove_circle, color: Colors.red, size: 18), onPressed: () => setState(() => items.removeAt(i))),
              ],
            ),
          );
        }),
      ],
    );
  }

  void _addItem(List<Map<String, dynamic>> items) {
    setState(() => items.add({'name': '', 'amount': 0.0}));
  }
}
